import 'package:material_ui/material_ui.dart';

/// Progress bar showing the live battery percentage and a distinct marker for the saved charging target.
class ChargingProgressBar extends StatelessWidget {
  const ChargingProgressBar({
    super.key,
    required this.batteryPercent,
    this.targetPercent,
    this.height = 14.0,
  });

  final double? batteryPercent;
  final int? targetPercent;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final batteryFraction =
        batteryPercent != null ? (batteryPercent!.clamp(0.0, 100.0) / 100.0) : 0.0;
    final targetFraction =
        targetPercent != null ? (targetPercent!.clamp(0, 100) / 100.0) : null;

    final progressColor = batteryPercent != null && batteryPercent! <= 20.0
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final barWidth = constraints.maxWidth;
            final targetX = targetFraction != null ? barWidth * targetFraction : null;

            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                // Background track
                Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(height / 2),
                  ),
                ),

                // Battery fill
                FractionallySizedBox(
                  widthFactor: batteryFraction,
                  child: Container(
                    height: height,
                    decoration: BoxDecoration(
                      color: progressColor,
                      borderRadius: BorderRadius.circular(height / 2),
                    ),
                  ),
                ),

                // Target marker
                if (targetX != null)
                  Positioned(
                    left: (targetX - 2.0).clamp(0.0, barWidth - 4.0),
                    child: Container(
                      key: const Key('target_marker'),
                      width: 4,
                      height: height + 8,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
