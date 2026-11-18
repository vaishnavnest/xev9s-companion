/// Vehicle connectivity telemetry state.
enum VehicleConnectivity {
  online('ONLINE'),
  offline('OFFLINE'),
  unknown('UNKNOWN');

  const VehicleConnectivity(this.wireValue);
  final String wireValue;

  /// Safe parser: converts raw string to [VehicleConnectivity], returning [unknown] if unrecognized.
  static VehicleConnectivity fromString(String? value) {
    if (value == null || value.trim().isEmpty) {
      return VehicleConnectivity.unknown;
    }
    final normalized = value.trim().toUpperCase();
    for (final conn in VehicleConnectivity.values) {
      if (conn.wireValue == normalized) {
        return conn;
      }
    }
    return VehicleConnectivity.unknown;
  }
}
