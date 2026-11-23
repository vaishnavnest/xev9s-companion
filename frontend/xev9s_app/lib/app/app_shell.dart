import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../core/theme/theme_provider.dart';
import 'widgets/xev_app_bar.dart';

class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  // The 8 routes correspond to the 8 StatefulShellBranches in router.dart:
  // 0: /home, 1: /location, 2: /charging, 3: /controls,
  // 4: /trips, 5: /analytics, 6: /notifications, 7: /profile

  String _getScreenTitle(int index) {
    switch (index) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Location';
      case 2:
        return 'Charging';
      case 3:
        return 'Controls';
      case 4:
        return 'Trips';
      case 5:
        return 'Driving & Energy';
      case 6:
        return 'Notifications';
      case 7:
        return 'Profile';
      default:
        return 'Dashboard';
    }
  }

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
          child: Consumer(
            builder: (context, ref, _) {
              final isDark = Theme.of(context).brightness == Brightness.dark;

              return Column(
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
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Profile'),
                    selected: navigationShell.currentIndex == 7,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _onDestinationSelected(7);
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Icon(
                        isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                        key: ValueKey(isDark),
                        color: isDark
                            ? const Color(0xFFFBBF24)
                            : const Color(0xFF0F766E),
                      ),
                    ),
                    title: Text(isDark ? 'Light Theme' : 'Dark Theme'),
                    subtitle: Text(
                      isDark ? 'Switch to day mode' : 'Switch to night mode',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: Switch(
                      value: isDark,
                      onChanged: (_) {
                        ref.read(themeModeProvider.notifier).toggleTheme(context);
                      },
                    ),
                    onTap: () {
                      ref.read(themeModeProvider.notifier).toggleTheme(context);
                    },
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = navigationShell.currentIndex;
    final currentTitle = _getScreenTitle(currentIndex);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;

        final appBar = XevAppBar(
          currentTitle: currentTitle,
          currentIndex: currentIndex,
          isWide: isWide,
          onNotificationTap: () => _onDestinationSelected(6),
          onLogoTap: () => _onDestinationSelected(0),
        );

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
