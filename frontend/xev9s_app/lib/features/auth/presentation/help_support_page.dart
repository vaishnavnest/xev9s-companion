import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/theme/app_theme.dart';

/// Help & Support screen accessible from the Sign In screen's help button.
class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? AppTheme.accentColor : AppTheme.primaryColor;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/login');
            }
          },
        ),
        title: Text(
          'Help & Support',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: isDark ? 0.14 : 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.support_agent_rounded,
                            color: accent,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'XEV 9S Connected Care',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Sign-in assistance, vehicle pairing, and account support.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _HelpItemCard(
                    accent: accent,
                    icon: Icons.lock_reset_rounded,
                    title: 'Trouble Signing In?',
                    description:
                        'Verify that you are using the email address registered with your XEV 9S account. Passwords are case-sensitive and must be at least 8 characters.',
                  ),
                  _HelpItemCard(
                    accent: accent,
                    icon: Icons.directions_car_outlined,
                    title: 'Pairing Your Vehicle',
                    description:
                        'New to XEV 9S Companion? Create an account first, then add your vehicle VIN from the Vehicles screen after signing in.',
                  ),
                  _HelpItemCard(
                    accent: accent,
                    icon: Icons.wifi_tethering_error_rounded,
                    title: 'Connection Issues',
                    description:
                        'Ensure your device has an active internet connection. If the server is unreachable, try again in a few moments.',
                  ),
                  const SizedBox(height: 8),
                  Card(
                    margin: EdgeInsets.zero,
                    color: theme.colorScheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: isDark ? 0.35 : 0.5,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.description_outlined, color: accent),
                          title: const Text('Terms of Service'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push('/terms'),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(Icons.privacy_tip_outlined, color: accent),
                          title: const Text('Privacy Policy'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push('/privacy'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HelpItemCard extends StatelessWidget {
  const _HelpItemCard({
    required this.accent,
    required this.icon,
    required this.title,
    required this.description,
  });

  final Color accent;
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(
            alpha: isDark ? 0.35 : 0.5,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
