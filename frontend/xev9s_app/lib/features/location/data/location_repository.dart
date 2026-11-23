import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../domain/vehicle_location.dart';

/// Abstract contract for vehicle location retrieval.
abstract class LocationRepository {
  /// Fetches the latest reported or last-known location for [vehicleId].
  ///
  /// Corresponds to `GET /vehicles/{vehicleId}/location`.
  /// Throws [AppError] on network, 403 (VEHICLE_ACCESS_DENIED) or 404 (VEHICLE_NOT_FOUND).
  Future<VehicleLocation> getLocation(String vehicleId);
}

/// Production implementation of [LocationRepository] backed by [ApiClient].
class ApiLocationRepository implements LocationRepository {
  ApiLocationRepository({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<VehicleLocation> getLocation(String vehicleId) async {
    return apiClient.get<VehicleLocation>(
      '/vehicles/$vehicleId/location',
      parse: (json) {
        if (json is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON map for VehicleLocationResponse');
        }
        return VehicleLocation.fromJson(json);
      },
    );
  }
}

/// Provider for [LocationRepository]. Overridable in tests.
final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiLocationRepository(apiClient: apiClient);
});
