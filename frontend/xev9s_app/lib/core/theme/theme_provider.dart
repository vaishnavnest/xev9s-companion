import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';

/// Provider for user-selected [ThemeMode] (light, dark, or system).
final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

/// Notifier managing dynamic theme switching and SharedPreferences persistence.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _prefKey = 'xev9s_theme_mode';

  @override
  ThemeMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final saved = prefs?.getString(_prefKey);
    if (saved == 'dark') return ThemeMode.dark;
    if (saved == 'light') return ThemeMode.light;
    return ThemeMode.system;
  }

  /// Toggles between Day Drive (light) and Night Drive (dark) mode.
  Future<void> toggleTheme(BuildContext context) async {
    final currentBrightness = Theme.of(context).brightness;
    final nextMode = currentBrightness == Brightness.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    state = nextMode;

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs?.setString(
      _prefKey,
      nextMode == ThemeMode.dark ? 'dark' : 'light',
    );
  }

  /// Explicitly sets the theme mode.
  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs?.setString(_prefKey, mode.name);
  }
}
