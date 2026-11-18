import 'package:material_ui/material_ui.dart';
import '../../core/utils/formatters.dart';

class StaleBanner extends StatelessWidget {
  const StaleBanner({
    super.key,
    this.message,
    this.lastUpdatedAt,
  });

  final String? message;
  final DateTime? lastUpdatedAt;

  String get _displayMessage {
    if (message != null) return message!;
    if (lastUpdatedAt != null) {
      return 'Vehicle is offline. Last reported: ${Formatters.formatRelative(lastUpdatedAt)}';
    }
    return 'Vehicle is offline. Showing last reported data.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.amber.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 18,
            color: Colors.amber.shade900,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _displayMessage,
              style: TextStyle(
                color: Colors.amber.shade900,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
