import 'package:equatable/equatable.dart';
import '../../../core/constants/app_constants.dart';
import 'vehicle_connectivity.dart';

export 'vehicle_connectivity.dart';

const _statusSentinel = Object();

typedef ConnectivityStatus = VehicleConnectivity;

/// Operational motion/power state of the vehicle.
enum VehicleState {
  parked('PARKED'),
  driving('DRIVING'),
  charging('CHARGING'),
  offline('OFFLINE'),
  unknown('UNKNOWN');

  const VehicleState(this.wireValue);
  final String wireValue;

  static VehicleState fromString(String? value) {
    if (value == null || value.trim().isEmpty) return VehicleState.unknown;
    final normalized = value.trim().toUpperCase();
    for (final state in VehicleState.values) {
      if (state.wireValue == normalized) return state;
    }
    return VehicleState.unknown;
  }
}

/// Central physical lock status of vehicle doors and closures.
enum LockState {
  locked('LOCKED'),
  unlocked('UNLOCKED'),
  unknown('UNKNOWN');

  const LockState(this.wireValue);
  final String wireValue;

  static LockState fromString(String? value) {
    if (value == null || value.trim().isEmpty) return LockState.unknown;
    final normalized = value.trim().toUpperCase();
    for (final state in LockState.values) {
      if (state.wireValue == normalized) return state;
    }
    return LockState.unknown;
  }
}

/// Remote HVAC climate pre-conditioning status.
enum PreconditioningState {
  active('ACTIVE'),
  inactive('INACTIVE'),
  unknown('UNKNOWN');

  const PreconditioningState(this.wireValue);
  final String wireValue;

  static PreconditioningState fromString(String? value) {
    if (value == null || value.trim().isEmpty) return PreconditioningState.unknown;
    final normalized = value.trim().toUpperCase();
    for (final state in PreconditioningState.values) {
      if (state.wireValue == normalized) return state;
    }
    return PreconditioningState.unknown;
  }
}

/// EV high-voltage battery charging status.
enum ChargingState {
  notConnected('NOT_CONNECTED'),
  connected('CONNECTED'),
  charging('CHARGING'),
  paused('PAUSED'),
  completed('COMPLETED'),
  interrupted('INTERRUPTED'),
  unknown('UNKNOWN');

  const ChargingState(this.wireValue);
  final String wireValue;

  static ChargingState fromString(String? value) {
    if (value == null || value.trim().isEmpty) return ChargingState.unknown;
    final normalized = value.trim().toUpperCase();
    if (normalized == 'DISCONNECTED') return ChargingState.notConnected;
    if (normalized == 'ACTIVE') return ChargingState.charging;
    for (final state in ChargingState.values) {
      if (state.wireValue == normalized) return state;
    }
    return ChargingState.unknown;
  }
}

/// Battery state severity classification.
enum BatteryLevel {
  normal('NORMAL'),
  warning('WARNING'),
  unavailable('UNAVAILABLE'),
  unknown('UNKNOWN');

  const BatteryLevel(this.wireValue);
  final String wireValue;

  static BatteryLevel fromString(String? value) {
    if (value == null || value.trim().isEmpty) return BatteryLevel.unknown;
    final normalized = value.trim().toUpperCase();
    for (final level in BatteryLevel.values) {
      if (level.wireValue == normalized) return level;
    }
    return BatteryLevel.unknown;
  }
}

/// High-voltage battery telemetry snapshot.
class BatterySummary extends Equatable {
  const BatterySummary({
    this.percent,
    this.level,
  });

  final double? percent;
  final BatteryLevel? level;

  factory BatterySummary.fromJson(Map<String, dynamic> json) {
    return BatterySummary(
      percent: (json['percent'] as num?)?.toDouble(),
      level: json['level'] != null ? BatteryLevel.fromString(json['level'] as String?) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        if (percent != null) 'percent': percent,
        if (level != null) 'level': level!.wireValue,
      };

  BatterySummary copyWith({
    double? percent,
    BatteryLevel? level,
  }) {
    return BatterySummary(
      percent: percent ?? this.percent,
      level: level ?? this.level,
    );
  }

  @override
  List<Object?> get props => [percent, level];
}

/// Estimated remaining driving range.
class RangeSummary extends Equatable {
  const RangeSummary({
    this.estimatedKm,
  });

  final double? estimatedKm;

  factory RangeSummary.fromJson(Map<String, dynamic> json) {
    return RangeSummary(
      estimatedKm: (json['estimatedKm'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (estimatedKm != null) 'estimatedKm': estimatedKm,
      };

  RangeSummary copyWith({
    double? estimatedKm,
  }) {
    return RangeSummary(
      estimatedKm: estimatedKm ?? this.estimatedKm,
    );
  }

  @override
  List<Object?> get props => [estimatedKm];
}

/// High-voltage charging session snapshot.
class ChargingSummary extends Equatable {
  const ChargingSummary({
    this.state = ChargingState.unknown,
    this.powerKw,
  });

  final ChargingState state;
  final double? powerKw;

  factory ChargingSummary.fromJson(Map<String, dynamic> json) {
    return ChargingSummary(
      state: json['state'] != null
          ? ChargingState.fromString(json['state'] as String?)
          : ChargingState.unknown,
      powerKw: (json['powerKw'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'state': state.wireValue,
        if (powerKw != null) 'powerKw': powerKw,
      };

  ChargingSummary copyWith({
    ChargingState? state,
    double? powerKw,
  }) {
    return ChargingSummary(
      state: state ?? this.state,
      powerKw: powerKw ?? this.powerKw,
    );
  }

  @override
  List<Object?> get props => [state, powerKw];
}

/// Primary Dashboard status representing the full physical and connected state of a vehicle.
class VehicleStatus extends Equatable {
  const VehicleStatus({
    required this.vehicleId,
    this.name,
    this.model,
    required this.vehicleState,
    required this.connectivity,
    this.battery,
    this.range,
    this.odometerKm,
    this.speedKmh,
    this.lockState,
    this.preconditioningState,
    this.charging,
    required this.lastUpdatedAt,
    this.isStale = false,
  });

  final String vehicleId;
  final String? name;
  final String? model;
  final VehicleState vehicleState;
  final ConnectivityStatus connectivity;
  final BatterySummary? battery;
  final RangeSummary? range;
  final double? odometerKm;
  final double? speedKmh;
  final LockState? lockState;
  final PreconditioningState? preconditioningState;
  final ChargingSummary? charging;
  final DateTime lastUpdatedAt;
  final bool isStale;

  /// Whether the vehicle is offline (connectivity offline OR vehicleState offline).
  bool get isOffline =>
      connectivity == ConnectivityStatus.offline || vehicleState == VehicleState.offline;

  /// Whether stale data banner should be displayed.
  bool get showStale => isStale || isOffline;

  /// Evaluates effective battery severity level (server provided or derived from percentage).
  BatteryLevel get effectiveBatteryLevel {
    final serverLevel = battery?.level;
    if (serverLevel != null && serverLevel != BatteryLevel.unknown) {
      return serverLevel;
    }
    final pct = battery?.percent;
    if (pct == null) {
      return BatteryLevel.unavailable;
    }
    if (pct <= AppConstants.lowBatteryWarningPercent) {
      return BatteryLevel.warning;
    }
    return BatteryLevel.normal;
  }

  factory VehicleStatus.fromJson(Map<String, dynamic> json) {
    final vehicleId = (json['vehicleId'] ?? json['vehicle_id']) as String?;
    if (vehicleId == null || vehicleId.trim().isEmpty) {
      throw const FormatException('Missing required field: vehicleId');
    }

    final rawVehicleState = (json['vehicleState'] ?? json['operating_state']) as String?;
    if (rawVehicleState == null) {
      throw const FormatException('Missing required field: vehicleState');
    }
    final vehicleState = VehicleState.fromString(rawVehicleState);

    final rawConnectivity = (json['connectivity'] ?? (json.containsKey('operating_state') ? 'ONLINE' : null)) as String?;
    if (rawConnectivity == null) {
      throw const FormatException('Missing required field: connectivity');
    }
    final connectivity = ConnectivityStatus.fromString(rawConnectivity);

    final rawLastUpdatedAt = (json['lastUpdatedAt'] ?? json['timestamp'] ?? json['received_at']) as String?;
    if (rawLastUpdatedAt == null) {
      throw const FormatException('Missing required field: lastUpdatedAt');
    }
    final lastUpdatedAt = DateTime.tryParse(rawLastUpdatedAt);
    if (lastUpdatedAt == null) {
      throw FormatException('Invalid ISO-8601 date for lastUpdatedAt: $rawLastUpdatedAt');
    }

    // Battery summary
    BatterySummary? battery;
    if (json['battery'] != null) {
      battery = BatterySummary.fromJson(json['battery'] as Map<String, dynamic>);
    } else if (json['battery_percentage'] != null || json['batteryPercent'] != null) {
      final pct = (json['battery_percentage'] ?? json['batteryPercent'] as num?)?.toDouble();
      battery = BatterySummary(percent: pct);
    }

    // Range summary
    RangeSummary? range;
    if (json['range'] != null) {
      range = RangeSummary.fromJson(json['range'] as Map<String, dynamic>);
    } else if (json['estimated_range_km'] != null || json['rangeKm'] != null) {
      final rkm = (json['estimated_range_km'] ?? json['rangeKm'] as num?)?.toDouble();
      range = RangeSummary(estimatedKm: rkm);
    }

    // Odometer & Speed
    final odometerKm = (json['odometerKm'] ?? json['odometer_km'] as num?)?.toDouble();
    final speedKmh = (json['speedKmh'] ?? json['speed_kph'] ?? json['speed'] as num?)?.toDouble();

    // Lock state
    LockState? lockState;
    if (json['lockState'] != null) {
      lockState = LockState.fromString(json['lockState'] as String?);
    } else if (json['is_locked'] != null) {
      lockState = json['is_locked'] == true ? LockState.locked : LockState.unlocked;
    }

    // Preconditioning state
    PreconditioningState? preconditioningState;
    if (json['preconditioningState'] != null) {
      preconditioningState = PreconditioningState.fromString(json['preconditioningState'] as String?);
    } else if (json['cabin_preconditioning_active'] != null) {
      preconditioningState = json['cabin_preconditioning_active'] == true ? PreconditioningState.active : PreconditioningState.inactive;
    }

    // Charging summary
    ChargingSummary? charging;
    if (json['charging'] != null) {
      charging = ChargingSummary.fromJson(json['charging'] as Map<String, dynamic>);
    } else if (json['charging_status'] != null || json['chargingState'] != null || json['charging_power_kw'] != null) {
      final cState = ChargingState.fromString(json['charging_status'] as String? ?? json['chargingState'] as String?);
      final pKw = (json['charging_power_kw'] ?? json['powerKw'] as num?)?.toDouble();
      charging = ChargingSummary(state: cState, powerKw: pKw);
    }

    return VehicleStatus(
      vehicleId: vehicleId,
      name: json['name'] as String?,
      model: json['model'] as String?,
      vehicleState: vehicleState,
      connectivity: connectivity,
      battery: battery,
      range: range,
      odometerKm: odometerKm,
      speedKmh: speedKmh,
      lockState: lockState,
      preconditioningState: preconditioningState,
      charging: charging,
      lastUpdatedAt: lastUpdatedAt,
      isStale: json['isStale'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'vehicleId': vehicleId,
        if (name != null) 'name': name,
        if (model != null) 'model': model,
        'vehicleState': vehicleState.wireValue,
        'connectivity': connectivity.wireValue,
        if (battery != null) 'battery': battery!.toJson(),
        if (range != null) 'range': range!.toJson(),
        if (odometerKm != null) 'odometerKm': odometerKm,
        if (speedKmh != null) 'speedKmh': speedKmh,
        if (lockState != null) 'lockState': lockState!.wireValue,
        if (preconditioningState != null)
          'preconditioningState': preconditioningState!.wireValue,
        if (charging != null) 'charging': charging!.toJson(),
        'lastUpdatedAt': lastUpdatedAt.toUtc().toIso8601String(),
        'isStale': isStale,
      };

  VehicleStatus copyWith({
    String? vehicleId,
    String? name,
    String? model,
    VehicleState? vehicleState,
    ConnectivityStatus? connectivity,
    Object? battery = _statusSentinel,
    Object? range = _statusSentinel,
    Object? odometerKm = _statusSentinel,
    Object? speedKmh = _statusSentinel,
    Object? lockState = _statusSentinel,
    Object? preconditioningState = _statusSentinel,
    Object? charging = _statusSentinel,
    DateTime? lastUpdatedAt,
    bool? isStale,
  }) {
    return VehicleStatus(
      vehicleId: vehicleId ?? this.vehicleId,
      name: name ?? this.name,
      model: model ?? this.model,
      vehicleState: vehicleState ?? this.vehicleState,
      connectivity: connectivity ?? this.connectivity,
      battery: identical(battery, _statusSentinel)
          ? this.battery
          : battery as BatterySummary?,
      range: identical(range, _statusSentinel)
          ? this.range
          : range as RangeSummary?,
      odometerKm: identical(odometerKm, _statusSentinel)
          ? this.odometerKm
          : odometerKm as double?,
      speedKmh: identical(speedKmh, _statusSentinel)
          ? this.speedKmh
          : speedKmh as double?,
      lockState: identical(lockState, _statusSentinel)
          ? this.lockState
          : lockState as LockState?,
      preconditioningState: identical(preconditioningState, _statusSentinel)
          ? this.preconditioningState
          : preconditioningState as PreconditioningState?,
      charging: identical(charging, _statusSentinel)
          ? this.charging
          : charging as ChargingSummary?,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      isStale: isStale ?? this.isStale,
    );
  }

  /// Merges a newer status into this status.
  /// If [newer] timestamp is older than [lastUpdatedAt], the update is ignored.
  VehicleStatus merge(VehicleStatus newer) {
    if (newer.lastUpdatedAt.isBefore(lastUpdatedAt)) {
      return this;
    }
    return newer.copyWith(
      name: newer.name ?? name,
      model: newer.model ?? model,
    );
  }

  @override
  List<Object?> get props => [
        vehicleId,
        name,
        model,
        vehicleState,
        connectivity,
        battery,
        range,
        odometerKm,
        speedKmh,
        lockState,
        preconditioningState,
        charging,
        lastUpdatedAt,
        isStale,
      ];
}
