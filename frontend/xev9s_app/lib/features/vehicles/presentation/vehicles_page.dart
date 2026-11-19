import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../auth/application/auth_controller.dart';
import '../application/vehicles_controller.dart';
import '../domain/vehicle_summary.dart';
import '../selected_vehicle_provider.dart';
import 'vehicle_card.dart';

class VehiclesPage extends ConsumerWidget {
  const VehiclesPage({super.key});

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Log out?',
      content: 'You will need to sign in again.',
      confirmLabel: 'Log Out',
      isDestructive: true,
    );

    if (confirmed) {
      await ref.read(authControllerProvider.notifier).logout();
      if (context.mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(vehiclesControllerProvider);
    final selectedId = ref.watch(selectedVehicleProvider);
    final isWide = MediaQuery.of(context).size.width >= 720;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Vehicles'),
        actions: [
          if (isWide)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Vehicle'),
                onPressed: () => context.push('/vehicles/add'),
              ),
            ),
          PopupMenuButton<String>(
            tooltip: 'More options',
            onSelected: (value) {
              if (value == 'logout') {
                _handleLogout(context, ref);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text('Log out'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: !isWide
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/vehicles/add'),
              icon: const Icon(Icons.add),
              label: const Text('Add Vehicle'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.read(vehiclesControllerProvider.notifier).refresh(),
        child: AsyncValueView<List<VehicleSummary>>(
          value: vehiclesAsync,
          onRetry: () => ref.read(vehiclesControllerProvider.notifier).refresh(),
          empty: EmptyState(
            icon: Icons.directions_car_outlined,
            title: 'No vehicles added',
            message: 'Pair your XEV 9S to get started with remote commands and telemetry.',
            actionLabel: 'Add Vehicle',
            onAction: () => context.push('/vehicles/add'),
          ),
          isEmpty: (list) => list.isEmpty,
          data: (vehicles) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  itemCount: vehicles.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (ctx, index) {
                    final vehicle = vehicles[index];
                    final isSelected = vehicle.vehicleId == selectedId;

                    return VehicleCard(
                      vehicle: vehicle,
                      isSelected: isSelected,
                      onTap: () async {
                        if (vehicle.isPending) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('This vehicle is still pending association.'),
                            ),
                          );
                          return;
                        }

                        await ref
                            .read(selectedVehicleProvider.notifier)
                            .select(vehicle.vehicleId);
                        if (context.mounted) {
                          context.go('/home');
                        }
                      },
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
