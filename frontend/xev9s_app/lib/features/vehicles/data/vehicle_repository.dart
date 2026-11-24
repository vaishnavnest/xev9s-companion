import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../domain/vehicle_summary.dart';

/// Abstract contract for vehicle discovery and association operations.
abstract class VehicleRepository {
  /// Fetches vehicles associated with the authenticated user.
  Future<List<VehicleSummary>> listVehicles();

  /// Associates a new vehicle with pairing code and returns the updated vehicle list.
  Future<List<VehicleSummary>> associateVehicle({
    required String identifier,
    required String pairingCode,
    String? name,
  });
}

/// Production implementation of [VehicleRepository] backed by [ApiClient].
class ApiVehicleRepository implements VehicleRepository {
  ApiVehicleRepository({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<List<VehicleSummary>> listVehicles() async {
    return apiClient.get<List<VehicleSummary>>(
      '/vehicles',
      parse: (json) {
        List<dynamic> list;
        if (json is List) {
          list = json;
        } else if (json is Map<String, dynamic> && json['vehicles'] is List) {
          list = json['vehicles'] as List;
        } else {
          throw const FormatException('Expected JSON list or {vehicles: [...]} for VehicleList');
        }
        return list
            .map((item) => VehicleSummary.fromJson(item as Map<String, dynamic>))
            .toList();
      },
    );
  }

  @override
  Future<List<VehicleSummary>> associateVehicle({
    required String identifier,
    required String pairingCode,
    String? name,
  }) async {
    final trimmedIdentifier = identifier.trim();
    final trimmedPairingCode = pairingCode.trim();

    final body = <String, dynamic>{
      'vehicle_id': trimmedIdentifier,
      'pairing_code': trimmedPairingCode,
    };

    return apiClient.post<List<VehicleSummary>>(
      '/vehicles/associate',
      body: body,
      parse: (json) {
        List<dynamic> list;
        if (json is List) {
          list = json;
        } else if (json is Map<String, dynamic> && json['vehicles'] is List) {
          list = json['vehicles'] as List;
        } else {
          throw const FormatException('Expected JSON list or {vehicles: [...]} for VehicleList');
        }
        return list
            .map((item) => VehicleSummary.fromJson(item as Map<String, dynamic>))
            .toList();
      },
    );
  }
}

/// Provider for [VehicleRepository]. Overridable in tests.
final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return ApiVehicleRepository(apiClient: client);
});
