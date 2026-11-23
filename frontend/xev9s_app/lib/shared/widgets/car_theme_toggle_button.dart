import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_provider.dart';

/// Clean Sun and Moon animated theme toggle button.
class CarThemeToggleButton extends ConsumerWidget {
  const CarThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final tooltip = isDark ? 'Switch to light theme' : 'Switch to dark theme';

    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, animation) => RotationTransition(
            turns: animation,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: Icon(
            isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
            key: ValueKey(isDark),
            size: 22,
            color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF0F766E),
          ),
        ),
        onPressed: () =>
            ref.read(themeModeProvider.notifier).toggleTheme(context),
      ),
    );
  }
}

/// Convenience alias for [CarThemeToggleButton].
typedef ThemeToggleButton = CarThemeToggleButton;
