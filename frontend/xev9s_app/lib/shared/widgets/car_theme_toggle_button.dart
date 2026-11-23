import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_provider.dart';

/// Automotive-inspired theme toggle button simulating vehicle headlights
/// and cockpit drive modes (Day Drive vs Night Drive).
class CarThemeToggleButton extends ConsumerWidget {
  const CarThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final tooltip = isDark
        ? 'Night Drive Active (Headlights On) — Tap for Day Drive'
        : 'Day Drive Active (Headlights Off) — Tap for Night Drive';

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () =>
                ref.read(themeModeProvider.notifier).toggleTheme(context),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0C2233)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF00E5FF).withValues(alpha: 0.6)
                      : const Color(0xFFCBD5E1),
                  width: 1.2,
                ),
                boxShadow: isDark
                    ? [
                        BoxShadow(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Headlight beam (cyan glowing in dark) vs Daytime sun (amber in light)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      isDark
                          ? Icons.highlight_rounded // Car headlamp high-beam symbol
                          : Icons.wb_sunny_rounded,
                      key: ValueKey(isDark),
                      size: 16,
                      color: isDark
                          ? const Color(0xFF00E5FF)
                          : const Color(0xFFD97706),
                    ),
                  ),
                  const SizedBox(width: 5),

                  // Car silhouette icon
                  Icon(
                    Icons.directions_car_rounded,
                    size: 16,
                    color: isDark
                        ? const Color(0xFFF8FAFC)
                        : const Color(0xFF334155),
                  ),

                  const SizedBox(width: 4),

                  // Automotive mode label
                  Text(
                    isDark ? 'NIGHT' : 'DAY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: isDark
                          ? const Color(0xFF00E5FF)
                          : const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
