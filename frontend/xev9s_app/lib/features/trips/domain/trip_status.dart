/// Lifecycle status of a vehicle trip (UC-06).
enum TripStatus {
  ongoing,
  completed,
  unknown;

  /// Parses API wire string (case-insensitive) into [TripStatus].
  static TripStatus fromApi(String? value) {
    if (value == null) return TripStatus.unknown;
    switch (value.trim().toLowerCase()) {
      case 'ongoing':
        return TripStatus.ongoing;
      case 'completed':
        return TripStatus.completed;
      default:
        return TripStatus.unknown;
    }
  }

  /// Wire value expected by the backend API.
  String? toApi() {
    switch (this) {
      case TripStatus.ongoing:
        return 'ongoing';
      case TripStatus.completed:
        return 'completed';
      case TripStatus.unknown:
        return null;
    }
  }
}
