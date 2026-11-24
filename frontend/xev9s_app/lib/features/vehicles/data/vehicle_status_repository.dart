import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../domain/vehicle_status.dart';

/// Abstract contract for vehicle telemetry and dashboard status retrieval.
abstract class VehicleStatusRepository {
  /// Fetches the latest telemetry and physical status for [vehicleId].
  ///
  /// Corresponds to `GET /vehicles/{vehicleId}/status`.
  /// Throws [AppError] on 403 (VEHICLE_ACCESS_DENIED) or 404 (VEHICLE_NOT_FOUND).
  Future<VehicleStatus> getStatus(String vehicleId);
}

/// Production implementation of [VehicleStatusRepository] backed by [ApiClient].
class ApiVehicleStatusRepository implements VehicleStatusRepository {
  ApiVehicleStatusRepository({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<VehicleStatus> getStatus(String vehicleId) async {
    return apiClient.get<VehicleStatus>(
      '/vehicles/$vehicleId/telemetry/latest',
      parse: (json) {
        if (json is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON map for VehicleStatusResponse');
        }
        return VehicleStatus.fromJson(json);
      },
    );
  }
}

/// Provider for [VehicleStatusRepository]. Overridable in tests.
final vehicleStatusRepositoryProvider = Provider<VehicleStatusRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiVehicleStatusRepository(apiClient: apiClient);
});
