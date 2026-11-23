import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide LockState;
import '../../../core/config/app_config.dart';
import '../../../core/realtime/realtime_providers.dart';
import '../../../core/realtime/realtime_service.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/stale_banner.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../vehicles/application/vehicle_status_provider.dart';
import '../../vehicles/domain/vehicle_status.dart';
import '../../vehicles/selected_vehicle_provider.dart';
import 'dashboard_view_model.dart';

/// Primary Dashboard screen displaying connected telemetry, range, battery,
/// vehicle controls, and real-time connectivity status for the active vehicle.
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  Timer? _relativeTimeTimer;

  @override
  void initState() {
    super.initState();
    // Refresh the relative last-updated timestamp display every 30 seconds
    _relativeTimeTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _relativeTimeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(realtimeCoordinatorProvider);
    final selectedVehicleId = ref.watch(selectedVehicleProvider);

    if (selectedVehicleId == null || selectedVehicleId.isEmpty) {
      return Scaffold(
        body: Center(
          child: EmptyState(
            icon: Icons.directions_car_outlined,
            title: 'No vehicle selected',
            message: 'Pair your XEV 9S or add one to view its live dashboard.',
            actionLabel: 'Add Vehicle',
            onAction: () => context.push('/vehicles/add'),
          ),
        ),
      );
    }

    final statusAsync = ref.watch(vehicleStatusProvider);
    final refreshError = ref.watch(vehicleStatusRefreshErrorProvider);
    final connectionStateAsync = ref.watch(realtimeConnectionStateProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(vehicleStatusProvider.notifier).refresh(),
        child: AsyncValueView<VehicleStatus?>(
          value: statusAsync,
          onRetry: () => ref.read(vehicleStatusProvider.notifier).refresh(),
          data: (status) {
            if (status == null) {
              return Center(
                child: EmptyState(
                  icon: Icons.directions_car_outlined,
                  title: 'No vehicle selected',
                  message: 'Pair your XEV 9S or add one to view its live dashboard.',
                  actionLabel: 'Add Vehicle',
                  onAction: () => context.push('/vehicles/add'),
                ),
              );
            }

            final vm = DashboardViewModel(status: status);
            return _DashboardContent(
              vm: vm,
              refreshError: refreshError,
              connectionState: connectionStateAsync.asData?.value ??
                  ref.read(realtimeServiceProvider).currentConnectionState,
            );
          },
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.vm,
    this.refreshError,
    required this.connectionState,
  });

  final DashboardViewModel vm;
  final Object? refreshError;
  final RealtimeConnectionState connectionState;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 720;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Stale banner if vehicle is offline or data is stale
              if (vm.showStale)
                StaleBanner(
                  message: vm.staleBannerMessage,
                  lastUpdatedAt: vm.status.lastUpdatedAt,
                ),

              // Small non-blocking error notice if a background refresh failed while keeping old data
              if (refreshError != null)
                Container(
                  color: Colors.amber.shade50,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 16, color: Colors.amber.shade900),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Could not refresh latest telemetry. Showing saved status.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Row: Vehicle details + Status Chips
                    _buildHeader(context),
                    const SizedBox(height: 16),

                    // Cards Layout: Single column on narrow, two-column grid on wide
                    if (!isWide) ...[
                      _buildBatteryCard(context),
                      const SizedBox(height: 12),
                      _buildVehicleInfoCard(context),
                      const SizedBox(height: 12),
                      _buildChargingCard(context),
                    ] else ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                _buildBatteryCard(context),
                                const SizedBox(height: 12),
                                _buildChargingCard(context),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildVehicleInfoCard(context),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Quick Action Buttons
                    _buildQuickActions(context),

                    const SizedBox(height: 16),

                    // Last Updated Row & Real-time connection badge
                    _buildFooterRow(context),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vm.displayName,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                vm.modelName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            StatusChip(
              label: vm.vehicleStateLabel,
              type: vm.vehicleStateType,
            ),
            StatusChip(
              label: vm.connectivityLabel,
              type: vm.connectivityType,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBatteryCard(BuildContext context) {
    final theme = Theme.of(context);

    final (dotColor, chipTextColor, chipBg) = switch (vm.effectiveBatteryLevel) {
      BatteryLevel.normal => (
          Colors.green.shade800,
          Colors.green.shade800,
          Colors.green.shade50,
        ),
      BatteryLevel.warning => (
          Colors.amber.shade900,
          Colors.amber.shade900,
          Colors.amber.shade50,
        ),
      BatteryLevel.unavailable || BatteryLevel.unknown => (
          theme.colorScheme.onSurfaceVariant,
          theme.colorScheme.onSurfaceVariant,
          theme.colorScheme.surfaceContainerHighest,
        ),
    };

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Semantics(
        label: vm.batterySemanticsLabel,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.go('/charging'),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.battery_charging_full_rounded,
                                size: 22,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'Battery & Range',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: chipBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: dotColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            vm.effectiveBatteryLevel == BatteryLevel.normal
                                ? 'NORMAL'
                                : vm.batteryLevelLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: chipTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 2. Metrics Row: Percent (Big Primary) & Estimated Range (Right aligned)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      vm.batteryPercentDisplay,
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.0,
                        color: vm.isLiveValuesDimmed
                            ? theme.colorScheme.primary.withValues(alpha: 0.4)
                            : theme.colorScheme.primary,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'ESTIMATED RANGE',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          vm.batteryRangeDisplay,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: vm.isLiveValuesDimmed
                                ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 3. Sub-row: Target Limit
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Target limit 80% (Daily)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 4. Progress bar with Thumb Bead & Scale underneath
                _BatteryRangeProgressBar(
                  fraction: vm.isBatteryUnavailable ? 0.0 : vm.batteryProgressFraction,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleInfoCard(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.speed_rounded,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Vehicle Telemetry',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              context,
              icon: Icons.alt_route_rounded,
              title: 'Odometer',
              value: vm.odometerDisplay,
            ),
            const Divider(height: 20),
            _buildInfoRow(
              context,
              icon: Icons.speed_outlined,
              title: 'Current Speed',
              value: vm.speedDisplay,
              isDimmed: vm.isLiveValuesDimmed,
            ),
            const Divider(height: 20),
            _buildInfoRow(
              context,
              icon: vm.lockStateIcon,
              title: 'Doors & Closures',
              value: vm.lockStateDisplay,
            ),
            const Divider(height: 20),
            _buildInfoRow(
              context,
              icon: Icons.ac_unit_rounded,
              title: 'Climate Pre-conditioning',
              value: vm.preconditioningDisplay,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    bool isDimmed = false,
  }) {
    final theme = Theme.of(context);
    final valueStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.bold,
      color: isDimmed ? theme.colorScheme.onSurface.withValues(alpha: 0.4) : null,
    );

    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isDimmed
              ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
              : theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDimmed
                  ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(value, style: valueStyle),
      ],
    );
  }

  Widget _buildChargingCard(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go('/charging'),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.ev_station_rounded,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Charging Status',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'State',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          vm.chargingStateDisplay,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: vm.isLiveValuesDimmed
                                ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Charging Power',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          vm.chargingPowerDisplay,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: vm.isLiveValuesDimmed
                                ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 450;

        final buttons = [
          _ActionButton(
            icon: Icons.location_on_outlined,
            label: 'Location',
            onPressed: () => context.go('/location'),
          ),
          _ActionButton(
            icon: Icons.bolt_rounded,
            label: 'Charging',
            onPressed: () => context.go('/charging'),
          ),
          _ActionButton(
            icon: Icons.tune_rounded,
            label: 'Remote Controls',
            onPressed: () => context.go('/controls'),
          ),
        ];

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              buttons[0],
              const SizedBox(height: 8),
              buttons[1],
              const SizedBox(height: 8),
              buttons[2],
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: buttons[0]),
            const SizedBox(width: 12),
            Expanded(child: buttons[1]),
            const SizedBox(width: 12),
            Expanded(child: buttons[2]),
          ],
        );
      },
    );
  }

  Widget _buildFooterRow(BuildContext context) {
    final theme = Theme.of(context);

    final connectionBadge = switch (AppConfig.realtimeMode) {
      RealtimeMode.polling => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sync_rounded, size: 14, color: Colors.blueGrey),
            const SizedBox(width: 4),
            Text(
              'Polling (${AppConfig.pollIntervalSeconds}s)',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.blueGrey),
            ),
          ],
        ),
      RealtimeMode.ws => switch (connectionState) {
          RealtimeConnectionState.connected => Row(
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
            ),
          RealtimeConnectionState.connecting => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 6),
                Text(
                  'Connecting...',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ],
            ),
          RealtimeConnectionState.reconnecting => Row(
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
                  'Reconnecting...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.amber.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          RealtimeConnectionState.disconnected => Row(
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
            ),
        },
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Tooltip(
          message: vm.exactLastUpdated,
          child: Text(
            'Updated ${vm.relativeLastUpdated}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        connectionBadge,
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: OutlinedButton.icon(
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onPressed,
      ),
    );
  }
}

class _BatteryRangeProgressBar extends StatelessWidget {
  const _BatteryRangeProgressBar({
    required this.fraction,
  });

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clampedFraction = fraction.clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        const barHeight = 14.0;
        const thumbSize = 16.0;
        final thumbLeft = (totalWidth * clampedFraction - thumbSize / 2)
            .clamp(0.0, totalWidth - thumbSize);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Track + Gradient + Dotted overlay + Thumb
            SizedBox(
              height: thumbSize,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Inset background track matching other cards
                  Container(
                    height: barHeight,
                    width: totalWidth,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(barHeight / 2),
                    ),
                  ),

                  // Gradient fill bar matching theme primary
                  if (clampedFraction > 0.0)
                    Container(
                      height: barHeight,
                      width: totalWidth * clampedFraction,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary.withValues(alpha: 0.8),
                            theme.colorScheme.primary,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(barHeight / 2),
                      ),
                      // Texture of tiny dots
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(barHeight / 2),
                        child: CustomPaint(
                          painter: _DottedPatternPainter(),
                        ),
                      ),
                    ),

                  // Thumb Indicator bead matching theme surface & primary
                  if (clampedFraction > 0.0)
                    Positioned(
                      left: thumbLeft,
                      child: Container(
                        width: thumbSize,
                        height: thumbSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.surface,
                          border: Border.all(
                            color: theme.colorScheme.primary,
                            width: 3.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.35),
                              blurRadius: 4,
                              spreadRadius: 0.5,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Scale marks: 0%, 20%, 40%, 60%, 80%, 100%
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [0, 20, 40, 60, 80, 100].map((val) {
                final isAccent = val == 60;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: isAccent ? 2.0 : 1.5,
                      height: isAccent ? 6.0 : 4.0,
                      decoration: BoxDecoration(
                        color: isAccent
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$val%',
                      style: TextStyle(
                        fontSize: isAccent ? 11 : 10,
                        fontWeight: isAccent ? FontWeight.bold : FontWeight.w500,
                        color: isAccent
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}

class _DottedPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    const spacing = 8.0;
    final cy = size.height / 2;
    for (double x = 6.0; x < size.width - 4.0; x += spacing) {
      canvas.drawCircle(Offset(x, cy), 1.2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
