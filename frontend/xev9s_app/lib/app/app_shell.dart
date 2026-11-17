import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../features/vehicles/selected_vehicle_provider.dart';

class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  // The 8 routes correspond to the 8 StatefulShellBranches in router.dart:
  // 0: /home, 1: /location, 2: /charging, 3: /controls,
  // 4: /trips, 5: /analytics, 6: /notifications, 7: /profile

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.insights_outlined),
                title: const Text('Driving & Energy'),
                selected: navigationShell.currentIndex == 5,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _onDestinationSelected(5);
                },
              ),
              ListTile(
                leading: const Badge(
                  label: Text('0'),
                  child: Icon(Icons.notifications_outlined),
                ),
                title: const Text('Notifications'),
                selected: navigationShell.currentIndex == 6,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _onDestinationSelected(6);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Profile'),
                selected: navigationShell.currentIndex == 7,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _onDestinationSelected(7);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleId = ref.watch(selectedVehicleProvider);
    final currentIndex = navigationShell.currentIndex;

    final appBar = AppBar(
      title: const Text('XEV 9S Companion'),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: ActionChip(
            avatar: const Icon(Icons.directions_car_outlined, size: 18),
            label: Text(vehicleId ?? 'Select Vehicle'),
            onPressed: () {
              context.push('/vehicles');
            },
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;

        if (isWide) {
          return Scaffold(
            appBar: appBar,
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: currentIndex,
                  onDestinationSelected: _onDestinationSelected,
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: Text('Home'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.location_on_outlined),
                      selectedIcon: Icon(Icons.location_on),
                      label: Text('Location'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.bolt_outlined),
                      selectedIcon: Icon(Icons.bolt),
                      label: Text('Charging'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.tune_outlined),
                      selectedIcon: Icon(Icons.tune),
                      label: Text('Controls'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.route_outlined),
                      selectedIcon: Icon(Icons.route),
                      label: Text('Trips'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.insights_outlined),
                      selectedIcon: Icon(Icons.insights),
                      label: Text('Driving & Energy'),
                    ),
                    NavigationRailDestination(
                      icon: Badge(
                        label: Text('0'),
                        child: Icon(Icons.notifications_outlined),
                      ),
                      selectedIcon: Badge(
                        label: Text('0'),
                        child: Icon(Icons.notifications),
                      ),
                      label: Text('Notifications'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: Text('Profile'),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: navigationShell),
              ],
            ),
          );
        }

        // Mobile / narrow layout (< 720 px):
        // 5 primary destinations (Home, Location, Charging, Controls, Trips) + "More" entry (index 5)
        final navBarIndex = currentIndex < 5 ? currentIndex : 5;

        return Scaffold(
          appBar: appBar,
          body: navigationShell,
          bottomNavigationBar: NavigationBar(
            selectedIndex: navBarIndex,
            onDestinationSelected: (index) {
              if (index < 5) {
                _onDestinationSelected(index);
              } else {
                _showMoreMenu(context);
              }
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.location_on_outlined),
                selectedIcon: Icon(Icons.location_on),
                label: 'Location',
              ),
              NavigationDestination(
                icon: Icon(Icons.bolt_outlined),
                selectedIcon: Icon(Icons.bolt),
                label: 'Charging',
              ),
              NavigationDestination(
                icon: Icon(Icons.tune_outlined),
                selectedIcon: Icon(Icons.tune),
                label: 'Controls',
              ),
              NavigationDestination(
                icon: Icon(Icons.route_outlined),
                selectedIcon: Icon(Icons.route),
                label: 'Trips',
              ),
              NavigationDestination(
                icon: Icon(Icons.more_horiz_outlined),
                selectedIcon: Icon(Icons.more_horiz),
                label: 'More',
              ),
            ],
          ),
        );
      },
    );
  }
}
