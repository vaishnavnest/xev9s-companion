import 'package:material_ui/material_ui.dart';
import '../../../shared/widgets/status_chip.dart';
import '../domain/association_status.dart';
import '../domain/vehicle_connectivity.dart';
import '../domain/vehicle_summary.dart';

/// Reusable card displaying vehicle details, association status, and connectivity.
class VehicleCard extends StatelessWidget {
  const VehicleCard({
    super.key,
    required this.vehicle,
    required this.isSelected,
    required this.onTap,
  });

  final VehicleSummary vehicle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final associationChip = switch (vehicle.associationStatus) {
      AssociationStatus.associated => const StatusChip(
          label: 'Associated',
          type: ChipStatusType.success,
          icon: Icons.check_circle_outline,
        ),
      AssociationStatus.pending => const StatusChip(
          label: 'Pending',
          type: ChipStatusType.warning,
          icon: Icons.hourglass_top_outlined,
        ),
      AssociationStatus.unknown => const StatusChip(
          label: 'Unknown',
          type: ChipStatusType.info,
        ),
    };

    final connectivityChip = switch (vehicle.connectivity) {
      VehicleConnectivity.online => const StatusChip(
          label: 'Online',
          type: ChipStatusType.success,
          icon: Icons.cloud_done_outlined,
        ),
      VehicleConnectivity.offline => const StatusChip(
          label: 'Offline',
          type: ChipStatusType.info,
          icon: Icons.cloud_off_outlined,
        ),
      _ => null, // Unknown connectivity is hidden
    };

    return Card(
      elevation: isSelected ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(80)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle.model,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (vehicle.name.trim().isNotEmpty &&
                            vehicle.name != vehicle.model) ...[
                          const SizedBox(height: 4),
                          Text(
                            vehicle.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'VIN / ID: ${vehicle.identifier}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  associationChip,
                  ?connectivityChip,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
