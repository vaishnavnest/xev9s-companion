import 'package:material_ui/material_ui.dart';

enum ChipStatusType {
  info,
  success,
  warning,
  error,
}

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.type = ChipStatusType.info,
    this.icon,
  });

  final String label;
  final ChipStatusType type;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (Color bg, Color fg) = switch (type) {
      ChipStatusType.success => (
          Colors.green.shade50,
          Colors.green.shade800,
        ),
      ChipStatusType.warning => (
          Colors.amber.shade50,
          Colors.amber.shade900,
        ),
      ChipStatusType.error => (
          Colors.red.shade50,
          Colors.red.shade800,
        ),
      ChipStatusType.info => (
          theme.colorScheme.surfaceContainerHighest,
          theme.colorScheme.onSurfaceVariant,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
