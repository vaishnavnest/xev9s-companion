import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xev9s_app/core/providers.dart';
import 'package:xev9s_app/features/vehicles/selected_vehicle_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SelectedVehicleNotifier', () {
    test('selects vehicle and persists across a simulated restart', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Session 1: Startup without selected vehicle
      final container1 = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      expect(container1.read(selectedVehicleProvider), isNull);

      // User selects a vehicle
      await container1
          .read(selectedVehicleProvider.notifier)
          .select('veh_9S0001');

      expect(container1.read(selectedVehicleProvider), equals('veh_9S0001'));
      expect(prefs.getString(SelectedVehicleNotifier.prefKey), equals('veh_9S0001'));

      container1.dispose();

      // Session 2: Simulated app restart with the same underlying SharedPreferences
      final container2 = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      // On restart, the vehicle ID should be loaded immediately from persistence
      expect(container2.read(selectedVehicleProvider), equals('veh_9S0001'));

      // User clears the selection
      await container2.read(selectedVehicleProvider.notifier).clear();
      expect(container2.read(selectedVehicleProvider), isNull);
      expect(prefs.getString(SelectedVehicleNotifier.prefKey), isNull);

      container2.dispose();
    });
  });
}
