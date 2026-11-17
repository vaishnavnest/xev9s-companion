import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/providers.dart';

/// Notifier holding the currently selected vehicle ID.
/// Persisted in SharedPreferences and loaded at startup.
class SelectedVehicleNotifier extends Notifier<String?> {
  static const prefKey = 'selected_vehicle_id';
  SharedPreferences? _prefs;

  @override
  String? build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    if (_prefs != null) {
      return _prefs!.getString(prefKey);
    }
    // Asynchronously load if SharedPreferences is not pre-initialized
    _loadFromDisk();
    return null;
  }

  Future<void> _loadFromDisk() async {
    _prefs ??= await SharedPreferences.getInstance();
    final savedId = _prefs?.getString(prefKey);
    if (savedId != null && state == null) {
      state = savedId;
    }
  }

  /// Selects a vehicle and persists its identifier.
  Future<void> select(String id) async {
    state = id;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setString(prefKey, id);
  }

  /// Clears the selected vehicle from state and disk.
  Future<void> clear() async {
    state = null;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.remove(prefKey);
  }
}

final selectedVehicleProvider =
    NotifierProvider<SelectedVehicleNotifier, String?>(
  SelectedVehicleNotifier.new,
);
