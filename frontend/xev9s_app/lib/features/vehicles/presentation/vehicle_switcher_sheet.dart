import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../application/vehicles_controller.dart';
import '../domain/vehicle_summary.dart';
import '../selected_vehicle_provider.dart';

/// Shows the vehicle switcher as a bottom sheet (width < 720) or a dialog (width >= 720).
Future<void> showVehicleSwitcher(BuildContext context) async {
  final width = MediaQuery.of(context).size.width;
  if (width < 720) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const VehicleSwitcherContent(),
    );
  } else {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: const VehicleSwitcherContent(),
        ),
      ),
    );
  }
}

class VehicleSwitcherContent extends ConsumerWidget {
  const VehicleSwitcherContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(vehiclesControllerProvider);
    final selectedId = ref.watch(selectedVehicleProvider);
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Switch Vehicle',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(),
            Flexible(
              child: AsyncValueView<List<VehicleSummary>>(
                value: vehiclesAsync,
                onRetry: () =>
                    ref.read(vehiclesControllerProvider.notifier).refresh(),
                data: (vehicles) {
                  if (vehicles.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'No vehicles linked yet.',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: vehicles.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (ctx, index) {
                      final v = vehicles[index];
                      final isSelected = v.vehicleId == selectedId;

                      return ListTile(
                        leading: Icon(
                          Icons.directions_car,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        title: Text(
                          v.displayName,
                          style: TextStyle(
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          '${v.model} • ${v.identifier}',
                          style: theme.textTheme.bodySmall,
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check, color: theme.colorScheme.primary)
                            : null,
                        enabled: v.isAssociated,
                        onTap: () async {
                          if (!v.isAssociated) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'This vehicle is still pending association.'),
                              ),
                            );
                            return;
                          }
                          await ref
                              .read(selectedVehicleProvider.notifier)
                              .select(v.vehicleId);
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add Vehicle'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.push('/vehicles/add');
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.tune),
                      label: const Text('Manage'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.go('/vehicles');
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
