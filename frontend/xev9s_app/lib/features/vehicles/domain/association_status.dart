/// Vehicle pairing / association lifecycle status.
enum AssociationStatus {
  associated('ASSOCIATED'),
  pending('PENDING'),
  unknown('UNKNOWN');

  const AssociationStatus(this.wireValue);
  final String wireValue;

  /// Safe parser: converts raw string to [AssociationStatus], returning [unknown] if unrecognized.
  static AssociationStatus fromString(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AssociationStatus.unknown;
    }
    final normalized = value.trim().toUpperCase();
    for (final status in AssociationStatus.values) {
      if (status.wireValue == normalized) {
        return status;
      }
    }
    return AssociationStatus.unknown;
  }
}
