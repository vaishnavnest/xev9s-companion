import 'package:material_ui/material_ui.dart';

/// Segmented capsule battery progress bar matching the custom design specification.
/// Displays 10 distinct rounded segments inside a recessed capsule, with a glossy
/// turquoise/teal gradient, partial segment filling, target marker, and percentage ticks.
/// Fully adaptive to both Light and Dark themes.
class ChargingProgressBar extends StatelessWidget {
  const ChargingProgressBar({
    super.key,
    required this.batteryPercent,
    this.targetPercent,
    this.height = 52.0,
  });

  final double? batteryPercent;
  final int? targetPercent;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final clampedBattery =
        batteryPercent != null ? batteryPercent!.clamp(0.0, 100.0) : 0.0;
    final targetFraction =
        targetPercent != null ? (targetPercent!.clamp(0, 100) / 100.0) : null;

    const segmentCount = 10;
    const segmentGap = 5.0;

    final capsuleBg = isDark
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
        : const Color(0xFFE9F1F0);
    final capsuleBorder = isDark
        ? theme.colorScheme.outlineVariant.withValues(alpha: 0.35)
        : const Color(0xFFD4E2E0);

    final targetMarkerColor = isDark
        ? const Color(0xFF2DD4BF)
        : const Color(0xFF0F766E);

    final tickColor = isDark
        ? theme.colorScheme.onSurfaceVariant
        : const Color(0xFF64748B);
    final centerTickColor = isDark
        ? const Color(0xFF2DD4BF)
        : const Color(0xFF0D9488);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final totalWidth = constraints.maxWidth;
            final targetX =
                targetFraction != null ? totalWidth * targetFraction : null;

            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                // Outer recessed capsule container
                Container(
                  height: height,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7.0, vertical: 6.0),
                  decoration: BoxDecoration(
                    color: capsuleBg,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: capsuleBorder,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: List.generate(segmentCount, (index) {
                      final segmentStart = index * 10.0;
                      final segmentEnd = (index + 1) * 10.0;

                      double fillRatio = 0.0;
                      if (batteryPercent != null) {
                        if (clampedBattery >= segmentEnd) {
                          fillRatio = 1.0;
                        } else if (clampedBattery > segmentStart) {
                          fillRatio = (clampedBattery - segmentStart) / 10.0;
                        }
                      }

                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: index < segmentCount - 1 ? segmentGap : 0.0,
                          ),
                          child: _Segment(
                            fillRatio: fillRatio,
                            isDark: isDark,
                            theme: theme,
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                // Target marker overlay
                if (targetX != null)
                  Positioned(
                    left: (targetX - 2.5).clamp(0.0, totalWidth - 5.0),
                    child: Container(
                      key: const Key('target_marker'),
                      width: 5,
                      height: height + 8,
                      decoration: BoxDecoration(
                        color: targetMarkerColor,
                        borderRadius: BorderRadius.circular(2.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.3),
                            blurRadius: 3,
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
        const SizedBox(height: 8),

        // Percentage scale ticks matching the design:
        // 0%, 25%, 50% (highlighted bold teal), 75%, 100%
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '0%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: tickColor,
              ),
            ),
            Text(
              '25%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: tickColor,
              ),
            ),
            Text(
              '50%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: centerTickColor,
              ),
            ),
            Text(
              '75%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: tickColor,
              ),
            ),
            Text(
              '100%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: tickColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.fillRatio,
    required this.isDark,
    required this.theme,
  });

  final double fillRatio;
  final bool isDark;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final emptyBg = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFEFF5F4);
    final emptyBorder = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFDCE6E4);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          color: emptyBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: emptyBorder, width: 1),
        ),
        child: fillRatio <= 0.0
            ? null
            : FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: fillRatio.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF26D0CE),
                        Color(0xFF14B8A6),
                        Color(0xFF0F766E),
                      ],
                      stops: [0.0, 0.45, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF14B8A6).withValues(
                          alpha: isDark ? 0.5 : 0.35,
                        ),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
