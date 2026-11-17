import 'package:material_ui/material_ui.dart';

class VehiclesPage extends StatelessWidget {
  const VehiclesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Vehicles')),
      body: const Center(
        child: Text('Vehicles Page (Placeholder)'),
      ),
    );
  }
}
