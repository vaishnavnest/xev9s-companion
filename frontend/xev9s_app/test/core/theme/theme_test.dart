import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xev9s_app/core/providers.dart';
import 'package:xev9s_app/core/theme/theme_provider.dart';
import 'package:xev9s_app/shared/widgets/car_theme_toggle_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeProvider & CarThemeToggleButton Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('themeModeProvider defaults to ThemeMode.system', () {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.system);
    });

    test('themeModeProvider restores saved dark mode', () async {
      await prefs.setString('xev9s_theme_mode', 'dark');

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.dark);
    });

    test('themeModeProvider restores saved light mode', () async {
      await prefs.setString('xev9s_theme_mode', 'light');

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.light);
    });

    testWidgets('CarThemeToggleButton renders Day mode and toggles to Night mode', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            home: const Scaffold(
              appBar: PreferredSize(
                preferredSize: Size.fromHeight(56),
                child: CarThemeToggleButton(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In light mode, renders DAY label and car icon
      expect(find.text('DAY'), findsOneWidget);
      expect(find.byIcon(Icons.directions_car_rounded), findsOneWidget);
      expect(find.byIcon(Icons.wb_sunny_rounded), findsOneWidget);

      // Tap the toggle
      await tester.tap(find.byType(CarThemeToggleButton));
      await tester.pumpAndSettle();

      expect(prefs.getString('xev9s_theme_mode'), 'dark');
    });

    testWidgets('CarThemeToggleButton renders Night mode with headlights beam in dark theme', (tester) async {
      await prefs.setString('xev9s_theme_mode', 'dark');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            themeMode: ThemeMode.dark,
            home: const Scaffold(
              appBar: PreferredSize(
                preferredSize: Size.fromHeight(56),
                child: CarThemeToggleButton(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In dark mode, renders NIGHT label and car headlamp high-beam icon
      expect(find.text('NIGHT'), findsOneWidget);
      expect(find.byIcon(Icons.highlight_rounded), findsOneWidget);
      expect(find.byIcon(Icons.directions_car_rounded), findsOneWidget);

      // Tap the toggle to switch back to Day Drive
      await tester.tap(find.byType(CarThemeToggleButton));
      await tester.pumpAndSettle();

      expect(prefs.getString('xev9s_theme_mode'), 'light');
    });
  });
}
