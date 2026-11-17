import 'package:equatable/equatable.dart';
import 'association_status.dart';
import 'vehicle_connectivity.dart';

/// Summary representation of an associated or pending vehicle.
class VehicleSummary extends Equatable {
  const VehicleSummary({
    required this.vehicleId,
    required this.name,
    required this.model,
    required this.identifier,
    required this.associationStatus,
    this.connectivity,
  });

  final String vehicleId;
  final String name;
  final String model;
  final String identifier;
  final AssociationStatus associationStatus;
  final VehicleConnectivity? connectivity;

  /// User-facing display name: custom friendly name if set and not empty, fallback to model.
  String get displayName => name.trim().isNotEmpty ? name : model;

  bool get isAssociated => associationStatus == AssociationStatus.associated;
  bool get isPending => associationStatus == AssociationStatus.pending;
  bool get isOnline => connectivity == VehicleConnectivity.online;
  bool get isOffline => connectivity == VehicleConnectivity.offline;

  factory VehicleSummary.fromJson(Map<String, dynamic> json) {
    final vehicleId = json['vehicleId'] as String?;
    final name = json['name'] as String?;
    final model = json['model'] as String?;
    final identifier = json['identifier'] as String?;
    final rawStatus = json['associationStatus'] as String?;
    final rawConnectivity = json['connectivity'] as String?;

    if (vehicleId == null || vehicleId.isEmpty) {
      throw const FormatException('Missing required field: vehicleId');
    }
    if (name == null) {
      throw const FormatException('Missing required field: name');
    }
    if (model == null || model.isEmpty) {
      throw const FormatException('Missing required field: model');
    }
    if (identifier == null || identifier.isEmpty) {
      throw const FormatException('Missing required field: identifier');
    }
    if (rawStatus == null || rawStatus.isEmpty) {
      throw const FormatException('Missing required field: associationStatus');
    }

    return VehicleSummary(
      vehicleId: vehicleId,
      name: name,
      model: model,
      identifier: identifier,
      associationStatus: AssociationStatus.fromString(rawStatus),
      connectivity: rawConnectivity != null
          ? VehicleConnectivity.fromString(rawConnectivity)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'vehicleId': vehicleId,
        'name': name,
        'model': model,
        'identifier': identifier,
        'associationStatus': associationStatus.wireValue,
        if (connectivity != null) 'connectivity': connectivity!.wireValue,
      };

  @override
  List<Object?> get props => [
        vehicleId,
        name,
        model,
        identifier,
        associationStatus,
        connectivity,
      ];
}
