import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../vehicles/selected_vehicle_provider.dart';
import '../../data/charging_repository.dart';
import '../../domain/charging_session.dart';

/// Provider fetching details for a single charging session by [sessionId].
final chargingSessionDetailProvider =
    FutureProvider.family<ChargingSession, String>((ref, sessionId) async {
  final repository = ref.watch(chargingRepositoryProvider);
  final vehicleId = ref.watch(selectedVehicleProvider);

  if (vehicleId == null || vehicleId.isEmpty) {
    throw StateError('No vehicle selected');
  }

  return repository.getSession(vehicleId, sessionId);
});
