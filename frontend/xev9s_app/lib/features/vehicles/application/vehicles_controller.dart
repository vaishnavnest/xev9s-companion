import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_exception.dart';
import '../data/vehicle_repository.dart';
import '../domain/association_status.dart';
import '../domain/vehicle_summary.dart';
import '../selected_vehicle_provider.dart';

/// AsyncNotifier managing the user's vehicles list and auto-selection logic.
class VehiclesController extends AsyncNotifier<List<VehicleSummary>> {
  late final VehicleRepository _repository;

  @override
  FutureOr<List<VehicleSummary>> build() async {
    _repository = ref.watch(vehicleRepositoryProvider);
    final vehicles = await _repository.listVehicles();
    Future.microtask(() => _handleAutoSelection(vehicles));
    return vehicles;
  }

  /// Reloads vehicle list without flashing a full-screen loading spinner.
  Future<void> refresh() async {
    // Preserve current data while fetching
    // ignore: invalid_use_of_internal_member
    state = const AsyncLoading<List<VehicleSummary>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final vehicles = await _repository.listVehicles();
      Future.microtask(() => _handleAutoSelection(vehicles));
      return vehicles;
    });
  }

  /// Associates a new vehicle and updates the list with the returned updated list.
  Future<List<VehicleSummary>> associate({
    required String identifier,
    required String pairingCode,
    String? name,
  }) async {
    try {
      final updatedList = await _repository.associateVehicle(
        identifier: identifier,
        pairingCode: pairingCode,
        name: name,
      );
      _handleAutoSelection(updatedList);
      state = AsyncData(updatedList);
      return updatedList;
    } on AppError {
      rethrow;
    }
  }

  /// Internal auto-selection and stale-selection synchronization.
  void _handleAutoSelection(List<VehicleSummary> vehicles) {
    final selectedId = ref.read(selectedVehicleProvider);
    final associatedVehicles =
        vehicles.where((v) => v.associationStatus == AssociationStatus.associated).toList();

    // 1. If exactly one ASSOCIATED vehicle and nothing is currently selected -> auto-select it.
    if ((selectedId == null || selectedId.isEmpty) && associatedVehicles.length == 1) {
      ref.read(selectedVehicleProvider.notifier).select(associatedVehicles.first.vehicleId);
      return;
    }

    // 2. If a vehicle is selected but no longer exists in the loaded list -> clear it.
    if (selectedId != null && selectedId.isNotEmpty) {
      final exists = vehicles.any((v) => v.vehicleId == selectedId);
      if (!exists) {
        ref.read(selectedVehicleProvider.notifier).clear();
      }
    }
  }
}

/// Provider for [VehiclesController].
final vehiclesControllerProvider =
    AsyncNotifierProvider<VehiclesController, List<VehicleSummary>>(
  VehiclesController.new,
);

/// Derived provider exposing the full [VehicleSummary] object of the currently selected vehicle.
final currentVehicleProvider = Provider<VehicleSummary?>((ref) {
  final selectedId = ref.watch(selectedVehicleProvider);
  if (selectedId == null || selectedId.isEmpty) return null;

  final vehiclesAsync = ref.watch(vehiclesControllerProvider);
  final vehicles = vehiclesAsync.asData?.value;
  if (vehicles == null) return null;

  for (final v in vehicles) {
    if (v.vehicleId == selectedId) {
      return v;
    }
  }
  return null;
});
