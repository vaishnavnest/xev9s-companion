import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import '../../core/theme/app_theme.dart';
import '../../features/vehicles/application/vehicles_controller.dart';
import '../../features/vehicles/presentation/vehicle_switcher_sheet.dart';
import '../../shared/widgets/car_theme_toggle_button.dart';
import '../../shared/widgets/xev_logo.dart';

/// Premium, responsive application bar for the XEV 9S Companion app.
///
/// Layout:
/// - Leftmost: Official Mahindra XEV Twin Peaks logo from the splash screen.
/// - Title / Center: Current active screen name.
/// - Right Actions: Theme headlights toggle, notification button (with badge),
///   and on the rightmost edge, the vehicle switcher pill displaying the selected car name.
class XevAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const XevAppBar({
    super.key,
    required this.currentTitle,
    required this.currentIndex,
    required this.onNotificationTap,
    this.onLogoTap,
    this.isWide = false,
  });

  final String currentTitle;
  final int currentIndex;
  final VoidCallback onNotificationTap;
  final VoidCallback? onLogoTap;
  final bool isWide;

  @override
  Size get preferredSize => Size.fromHeight(isWide ? 64.0 : 56.0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentVehicle = ref.watch(currentVehicleProvider);

    final isNotificationsActive = currentIndex == 6;

    final bottomBorderColor = isDark
        ? AppTheme.accentColor.withValues(alpha: 0.22)
        : AppTheme.primaryColor.withValues(alpha: 0.14);

    final appBarBg = isDark
        ? const Color(0xFF030D11)
        : const Color(0xFFF9FBFC);

    final leadingWidth = isWide ? 64.0 : 56.0;
    final leadingWidget = Center(
      child: Tooltip(
        message: 'Go to Dashboard',
        child: InkWell(
          onTap: onLogoTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
            child: XevAppLogo(height: isWide ? 30 : 26),
          ),
        ),
      ),
    );

    Widget titleWidget;
    if (isWide) {
      titleWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'XEV 9S',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 1.4,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 1,
            height: 20,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
          const SizedBox(width: 14),
          Text(
            currentTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              letterSpacing: 0.3,
            ),
          ),
        ],
      );
    } else {
      titleWidget = Text(
        currentTitle,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 17,
          letterSpacing: 0.2,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: appBarBg,
      leading: leadingWidget,
      leadingWidth: leadingWidth,
      centerTitle: false,
      title: titleWidget,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(
          color: bottomBorderColor,
          height: 1.0,
        ),
      ),
      actions: [
        if (isWide) const CarThemeToggleButton(),
        IconButton(
          tooltip: 'Notifications',
          icon: Badge(
            label: const Text('0'),
            backgroundColor: isNotificationsActive ? AppTheme.accentColor : null,
            child: Icon(
              isNotificationsActive
                  ? Icons.notifications_rounded
                  : Icons.notifications_outlined,
              color: isNotificationsActive ? AppTheme.accentColor : null,
            ),
          ),
          onPressed: onNotificationTap,
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12.0, left: 4.0),
          child: _VehicleSwitcherButton(
            vehicleName: currentVehicle?.displayName ?? 'Select vehicle',
            isWide: isWide,
            onPressed: () => showVehicleSwitcher(context),
          ),
        ),
      ],
    );
  }
}

/// Cockpit-style pill button showing the active vehicle name and chevron.
class _VehicleSwitcherButton extends StatelessWidget {
  const _VehicleSwitcherButton({
    required this.vehicleName,
    required this.isWide,
    required this.onPressed,
  });

  final String vehicleName;
  final bool isWide;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark
        ? const Color(0xFF07191E)
        : const Color(0xFFE8F5F5);

    final borderColor = isDark
        ? AppTheme.accentColor.withValues(alpha: 0.40)
        : AppTheme.primaryColor.withValues(alpha: 0.35);

    final accent = isDark ? AppTheme.accentColor : AppTheme.primaryColor;

    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: 'Switch Vehicle ($vehicleName)',
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isWide ? 220 : 125,
              minHeight: 36,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 12 : 8,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.directions_car_rounded,
                  size: isWide ? 18 : 16,
                  color: accent,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    vehicleName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isWide ? 13 : 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
